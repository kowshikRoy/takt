import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/dictionary_service.dart';
import '../services/vocabulary_service.dart';
import '../services/tts_service.dart';
import '../models/saved_word.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

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
  Map<String, dynamic>? _selectedWord;
  
  bool _isSearching = false;
  bool _isLoadingDiscover = true;
  String _selectedPosFilter = 'all'; // 'all', 'noun', 'verb', 'adj'
  int _selectedTabIndex = 0; // 0: Forms/Declension, 1: Examples, 2: Related
  Set<String> _savedWordIds = {};

  List<Map<String, dynamic>> get _filteredDiscoverWords {
    if (_selectedPosFilter == 'all') {
      return _masterDiscoverWords;
    }
    return _masterDiscoverWords
        .where((w) => (w['pos']?.toString().toLowerCase() ?? '') == _selectedPosFilter.toLowerCase())
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadDiscoverWords();
    _loadSavedWordStatus();
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
      // Filter by POS if selected
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
        _isSearching = false;
        _searchController.text = fullWord['word'] ?? '';
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
      final primaryDef = (defs != null && defs.isNotEmpty) ? defs.first.toString() : '';
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSearchBar(context),
                        const SizedBox(height: 12),
                        _buildFilterPills(context),
                        const SizedBox(height: 20),

                        if (_selectedWord != null) ...[
                          _buildMainCard(context, _selectedWord!),
                          const SizedBox(height: 20),
                          _buildTabs(context),
                          const SizedBox(height: 16),
                          _buildTabContent(context, _selectedWord!),
                        ] else ...[
                          _buildDiscoverSection(context),
                        ],
                      ],
                    ),
                  ),

                  // Instant Search Results Overlay Dropdown
                  if (_isSearching && _searchResults.isNotEmpty)
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
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ListView.separated(
                            shrinkWrap: true,
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
                              if (gender == 'm' || gender == 'masculine') dotColor = AppTheme.genderMasc;
                              if (gender == 'f' || gender == 'feminine') dotColor = AppTheme.genderFem;
                              if (gender == 'n' || gender == 'neuter') dotColor = AppTheme.genderNeu;

                              return ListTile(
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
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (pos.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(width: 8),
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
                'Offline Database v16.0 • 50,000+ Words',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: colorScheme.onSurfaceVariant),
            tooltip: 'Refresh Discover List',
            onPressed: _loadDiscoverWords,
          ),
        ],
      ),
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
                  icon: Icon(Icons.close_rounded, color: colorScheme.onSurfaceVariant),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _isSearching = false;
                      _selectedWord = null;
                    });
                  },
                )
              : null,
          hintText: 'Search German word or definition...',
          hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
      {'id': 'noun', 'label': 'Nouns'},
      {'id': 'verb', 'label': 'Verbs'},
      {'id': 'adj', 'label': 'Adjectives'},
    ];

    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedPosFilter == f['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                f['label']!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
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
        }).toList(),
      ),
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.3,
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
            if (gender == 'm' || gender == 'masculine') genderColor = AppTheme.genderMasc;
            if (gender == 'f' || gender == 'feminine') genderColor = AppTheme.genderFem;
            if (gender == 'n' || gender == 'neuter') genderColor = AppTheme.genderNeu;

            return InkWell(
              onTap: () => _onResultSelected(item),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
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
            top: -24, right: -24,
            child: Container(
              width: 110, height: 110,
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    if (freq != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.bolt_rounded, size: 13, color: colorScheme.primary),
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
                  ],
                ),
                
                const SizedBox(height: 16),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    if (article.isNotEmpty) ...[
                      Text(
                        article,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: genderColor,
                        ),
                      ),
                      const SizedBox(width: 8),
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
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
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
                          backgroundColor: isSaved ? Colors.green : colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: Icon(
                          isSaved ? Icons.check_circle_rounded : Icons.bookmark_add_rounded,
                          size: 18,
                        ),
                        label: Text(
                          isSaved ? 'Saved in Learning Deck' : 'Add to Learning Deck',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                        icon: Icon(Icons.volume_up_rounded, color: colorScheme.primary),
                        onPressed: () {
                          final speakText = article.isNotEmpty ? '$article $word' : word;
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
    final tabs = ['Forms / Declension', 'Examples', 'Related Words'];

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final title = entry.value;
          final isActive = _selectedTabIndex == index;

          return GestureDetector(
            onTap: () => setState(() => _selectedTabIndex = index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: isActive
                    ? Border(bottom: BorderSide(color: colorScheme.primary, width: 2.5))
                    : null,
              ),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
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

  Widget _buildDeclensionTab(BuildContext context, Map<String, dynamic> wordData) {
    final forms = (wordData['forms'] as List?) ?? [];
    final colorScheme = Theme.of(context).colorScheme;

    if (forms.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: Text('No declension forms available.', style: TextStyle(color: colorScheme.onSurfaceVariant)),
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
              Icon(Icons.table_chart_rounded, size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Inflected & Declension Forms (${forms.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formStr,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    if (tagStr.isNotEmpty)
                      Text(
                        tagStr.toString().replaceAll('[', '').replaceAll(']', '').replaceAll('"', ''),
                        style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
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

  Widget _buildExamplesTab(BuildContext context, Map<String, dynamic> wordData) {
    final colorScheme = Theme.of(context).colorScheme;
    final wordStr = wordData['word']?.toString() ?? '';

    final sampleExamples = [
      {
        'de': 'Das ist eine wichtige $wordStr für unsere Arbeit.',
        'en': 'That is an important $wordStr for our work.',
      },
      {
        'de': 'Wir müssen die $wordStr genau verstehen.',
        'en': 'We need to understand the $wordStr precisely.',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sampleExamples.map((ex) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ex['de']!,
                  style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  ex['en']!,
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
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
        child: Text('No related words found.', style: TextStyle(color: colorScheme.onSurfaceVariant)),
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
          if (relType == 'synonym') chipColor = Colors.green.withValues(alpha: 0.15);
          if (relType == 'antonym') chipColor = Colors.red.withValues(alpha: 0.15);

          return ActionChip(
            label: Text('$relWord ($relType)'),
            backgroundColor: chipColor,
            onPressed: () {
              _searchController.text = relWord;
              _onSearchChanged(relWord);
            },
          );
        }).toList(),
      ),
    );
  }
}
