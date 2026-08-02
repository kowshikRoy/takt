import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../services/dictionary_service.dart';
import '../services/vocabulary_service.dart';
import '../services/tts_service.dart';
import '../models/saved_word.dart';
import '../theme/breakpoints.dart';

class DictionaryScreen extends StatefulWidget {
  final String? initialSearchQuery;
  const DictionaryScreen({super.key, this.initialSearchQuery});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DictionaryService _dictionaryService = DictionaryService();
  final VocabularyService _vocabService = VocabularyService();
  final TtsService _ttsService = TtsService();

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _masterDiscoverWords = [];
  List<Map<String, dynamic>> _recentWords = [];
  Map<String, dynamic>? _selectedWord;
  Future<String?>? _wordImageFuture;

  bool _isSearching = false;
  bool _isLoadingDiscover = true;
  String _selectedPosFilter = 'all'; // 'all', 'noun', 'verb', 'adj'
  int _selectedTabIndex = 0; // 0: Forms/Declension, 1: Examples, 2: Related
  Set<String> _savedWordIds = {};

  List<Map<String, dynamic>> get _filteredDiscoverWords {
    if (_selectedPosFilter == 'saved') {
      return _masterDiscoverWords.where((w) {
        final wordStr = (w['word']?.toString() ?? '').toLowerCase().trim();
        final idStr = (w['id']?.toString() ?? '').toLowerCase().trim();
        return _savedWordIds.contains(wordStr) || _savedWordIds.contains(idStr);
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
    if (widget.initialSearchQuery != null &&
        widget.initialSearchQuery!.isNotEmpty) {
      _searchController.text = widget.initialSearchQuery!;
      _onSearchChanged(widget.initialSearchQuery!);
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
          _savedWordIds = saved.map((w) => w.id.toLowerCase().trim()).toSet();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadDiscoverWords() async {
    setState(() => _isLoadingDiscover = true);
    final saved = await _vocabService.getSavedWords();
    final learnedCount = saved.length;

    final words = await _dictionaryService.getHighFrequencyWords(
      pos: 'all',
      limit: 30,
      learnedCount: learnedCount,
    );
    if (mounted) {
      setState(() {
        _masterDiscoverWords = words;
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
      final filtered = _selectedPosFilter == 'all'
          ? results
          : results.where((r) => r['pos'] == _selectedPosFilter).toList();
      setState(() {
        _searchResults = filtered;
      });
    }
  }

  void _onResultSelected(Map<String, dynamic> result) async {
    final fullWord = await _dictionaryService.getWordDetails(result['id']);
    if (mounted && fullWord != null) {
      setState(() {
        _selectedWord = fullWord;
        _wordImageFuture = _dictionaryService.getWordImageUrl(
          fullWord['word']?.toString() ?? '',
          pos: fullWord['pos']?.toString(),
        );
        _isSearching = false;
        _searchResults.clear();
        _searchController.clear();

        // Track in Recently Viewed Stack
        final wordId = fullWord['id'] ?? fullWord['word'];
        _recentWords.removeWhere((w) => (w['id'] ?? w['word']) == wordId);
        _recentWords.insert(0, fullWord);
        if (_recentWords.length > 10) {
          _recentWords.removeLast();
        }
      });
    }
  }

  Future<void> _toggleSaveWord(Map<String, dynamic> wordData) async {
    final wordStr = wordData['word'].toString();
    final wordId = wordStr.toLowerCase().trim();
    final isSaved = _savedWordIds.contains(wordId);

    if (isSaved) {
      await _vocabService.removeWord(wordId);
      setState(() {
        _savedWordIds.remove(wordId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed "$wordStr" from Learning List')),
        );
      }
    } else {
      final defs = wordData['definitions'] as List?;
      final primaryDef = (defs != null && defs.isNotEmpty)
          ? defs.first.toString()
          : '';
      final saved = SavedWord(
        id: wordId,
        word: wordStr,
        gender: wordData['gender']?.toString(),
        ipa: wordData['ipa']?.toString(),
        primaryDefinition: primaryDef,
        category: VocabCategory.learning,
      );
      await _vocabService.upsertWord(saved);
      setState(() {
        _savedWordIds.add(wordId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved "$wordStr" to Learning List! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = WindowClass.of(context).isAtLeastExpanded;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: isDesktop
            ? _buildDesktopMasterDetailLayout(context)
            : _buildMobileLayout(context),
      ),
    );
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
        _buildHeader(context, showBackButton: _selectedWord != null),
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
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _buildTabContent(context, _selectedWord!),
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
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 320),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: _buildSearchResultsList(context),
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
              onPressed: () {
                setState(() {
                  _selectedWord = null;
                  _wordImageFuture = null;
                });
              },
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'German Dictionary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                '50,000+ Words • Frequency Indexed',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Refresh Discover List',
            onPressed: _loadDiscoverWords,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsList(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
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
                      borderRadius: BorderRadius.circular(6),
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
            trailing: freq != null
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#$freq',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  )
                : null,
            onTap: () => _onResultSelected(item),
          );
        },
      ),
    );
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
                borderRadius: BorderRadius.circular(18),
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
                    borderRadius: BorderRadius.circular(18),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
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
      {'id': 'all', 'label': 'All Words'},
      {'id': 'saved', 'label': '⭐️ My Deck (${_savedWordIds.length})'},
      {'id': 'noun', 'label': 'Nouns'},
      {'id': 'verb', 'label': 'Verbs'},
      {'id': 'adj', 'label': 'Adjectives'},
    ];

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...filters.map((f) {
                final isSelected = _selectedPosFilter == f['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      f['label']!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: colorScheme.primary,
                    backgroundColor: colorScheme.surfaceContainerHigh,
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
              ActionChip(
                avatar: const Icon(Icons.menu_book_rounded, size: 14),
                label: Text('Browse Deck (${_savedWordIds.length})'),
                backgroundColor: colorScheme.secondaryContainer,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSecondaryContainer,
                ),
                onPressed: () => _showMyDeckDialog(context),
              ),
            ],
          ),
        ),
      ],
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
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.8,
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'My Saved Vocabulary (${allWords.length} Words)',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: allWords.isEmpty
                    ? const Center(
                        child: Text(
                          'No words saved yet.\nTap the bookmark icon on any word to add it to your deck!',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: allWords.length,
                        itemBuilder: (ctx, index) {
                          final w = allWords[index];
                          Color color = Colors.blue;
                          if (w.gender == 'masculine' || w.gender == 'm')
                            color = AppTheme.genderMasc;
                          if (w.gender == 'feminine' || w.gender == 'f')
                            color = AppTheme.genderFem;
                          if (w.gender == 'neuter' || w.gender == 'n')
                            color = AppTheme.genderNeu;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.2),
                              child: Text(
                                w.word.isNotEmpty
                                    ? w.word[0].toUpperCase()
                                    : 'W',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              w.word,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${w.category.name.toUpperCase()} • Interval: ${w.interval}d • Ease: ${w.easeFactor.toStringAsFixed(1)}x',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () async {
                              Navigator.pop(ctx);
                              final fullWord = await _dictionaryService
                                  .lookupWord(w.word);
                              if (mounted && fullWord != null) {
                                _onResultSelected(fullWord);
                              } else {
                                _searchController.text = w.word;
                                _onSearchChanged(w.word);
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
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
          'No matching vocabulary entries found.',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Explore Top Frequency Words',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
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
            final gender = item['gender']?.toString();
            final def = item['definition']?.toString() ?? '';
            final freq = item['freq_rank'];

            Color genderColor = colorScheme.primary;
            if (gender == 'm' || gender == 'masculine')
              genderColor = AppTheme.genderMasc;
            if (gender == 'f' || gender == 'feminine')
              genderColor = AppTheme.genderFem;
            if (gender == 'n' || gender == 'neuter')
              genderColor = AppTheme.genderNeu;

            return InkWell(
              onTap: () => _onResultSelected(item),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: genderColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
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
                        if (freq != null)
                          Text(
                            '#$freq',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _ttsService.speak(word),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2.0,
                            ),
                            child: Icon(
                              Icons.volume_up_rounded,
                              size: 15,
                              color: colorScheme.primary.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      def,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
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

  String _getCefrLevel(int? freqRank) {
    if (freqRank == null || freqRank <= 0) return 'B1';
    if (freqRank <= 500) return 'A1';
    if (freqRank <= 1500) return 'A2';
    if (freqRank <= 3500) return 'B1';
    if (freqRank <= 6000) return 'B2';
    return 'C1';
  }

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
            borderRadius: BorderRadius.circular(16),
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

  Widget _buildMainCard(BuildContext context, Map<String, dynamic> wordData) {
    final colorScheme = Theme.of(context).colorScheme;
    final gender = wordData['gender']?.toString();
    final word = wordData['word']?.toString() ?? '';
    final ipa = wordData['ipa']?.toString();
    final freq = wordData['freq_rank'];
    final defs = (wordData['definitions'] as List?) ?? [];
    final isSaved = _savedWordIds.contains(word.toLowerCase().trim());

    Color genderColor = colorScheme.primary;
    String genderText = wordData['pos']?.toString().toUpperCase() ?? "TERM";
    String article = "";

    if (gender == 'masculine' || gender == 'm') {
      genderColor = AppTheme.genderMasc;
      genderText = "MASCULINE (DER)";
      article = "Der";
    } else if (gender == 'feminine' || gender == 'f') {
      genderColor = AppTheme.genderFem;
      genderText = "FEMININE (DIE)";
      article = "Die";
    } else if (gender == 'neuter' || gender == 'n') {
      genderColor = AppTheme.genderNeu;
      genderText = "NEUTER (DAS)";
      article = "Das";
    }

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: genderColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        genderText,
                        style: TextStyle(
                          color: genderColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    if (freq != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 13,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Rank #$freq',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_getCefrLevel(freq)} • CEFR',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ],
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
                          borderRadius: BorderRadius.circular(8),
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
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        word,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),

                if (ipa != null && ipa.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    ipa,
                    style: GoogleFonts.notoSans(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Numbered Definitions List
                if (defs.isNotEmpty)
                  Column(
                    children: defs.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final d = entry.value.toString();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          defs.length > 1 ? '$idx. $d' : d,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 20),

                // Action Buttons (Save & TTS Audio)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _toggleSaveWord(wordData),
                        style: FilledButton.styleFrom(
                          backgroundColor: isSaved
                              ? Colors.green
                              : colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: Icon(
                          isSaved
                              ? Icons.check_circle_rounded
                              : Icons.bookmark_add_rounded,
                          size: 18,
                        ),
                        label: Text(
                          isSaved
                              ? 'Saved in Learning Deck'
                              : 'Add to Learning Deck',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.volume_up_rounded,
                          color: colorScheme.primary,
                        ),
                        tooltip: 'Play pronunciation',
                        onPressed: () {
                          final speakText = article.isNotEmpty
                              ? '$article $word'
                              : word;
                          _ttsService.speak(speakText, lang: 'de-DE');
                        },
                      ),
                    ),
                  ],
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
    final tabs = ['Forms & Declension', 'Examples', 'Related Words'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
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
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
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
    if (_selectedTabIndex == 0) {
      return _buildDeclensionTab(context, wordData);
    } else if (_selectedTabIndex == 1) {
      return _buildExamplesTab(context, wordData);
    } else {
      return _buildRelatedTab(context, wordData);
    }
  }

  Widget _buildDeclensionTab(
    BuildContext context,
    Map<String, dynamic> wordData,
  ) {
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
        borderRadius: BorderRadius.circular(16),
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
                  borderRadius: BorderRadius.circular(10),
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
          borderRadius: BorderRadius.circular(16),
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
        borderRadius: BorderRadius.circular(16),
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

  Widget _buildRelatedTab(BuildContext context, Map<String, dynamic> wordData) {
    final colorScheme = Theme.of(context).colorScheme;
    final relations = (wordData['relations'] as List?) ?? [];

    if (relations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: Text(
          'No related words found.',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: relations.map<Widget>((r) {
          final relWord = r['related_word'] ?? '';
          final relType = r['relation_type'] ?? 'related';

          Color chipColor = colorScheme.primaryContainer;
          if (relType == 'synonym')
            chipColor = Colors.green.withValues(alpha: 0.15);
          if (relType == 'antonym')
            chipColor = Colors.red.withValues(alpha: 0.15);

          return ActionChip(
            label: Text('$relWord ($relType)'),
            backgroundColor: chipColor,
            onPressed: () async {
              final fullWord = await _dictionaryService.lookupWord(relWord);
              if (mounted && fullWord != null) {
                _onResultSelected(fullWord);
              } else {
                _searchController.text = relWord;
                _onSearchChanged(relWord);
              }
            },
          );
        }).toList(),
      ),
    );
  }
}
