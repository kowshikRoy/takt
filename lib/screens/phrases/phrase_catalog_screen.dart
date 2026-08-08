import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/german_phrase.dart';
import '../../services/phrase_service.dart';
import '../../widgets/capped_width.dart';
import '../../widgets/phrase_card.dart';
import '../../widgets/phrase_detail_sheet.dart';
import 'phrase_practice_screen.dart';

class PhraseCatalogScreen extends StatefulWidget {
  final String? initialCategory;
  final String? initialLevel;

  const PhraseCatalogScreen({
    super.key,
    this.initialCategory,
    this.initialLevel,
  });

  @override
  State<PhraseCatalogScreen> createState() => _PhraseCatalogScreenState();
}

class _PhraseCatalogScreenState extends State<PhraseCatalogScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'All';
  String _selectedLevel = 'All';
  bool _showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    if (widget.initialLevel != null) {
      _selectedLevel = widget.initialLevel!;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final phraseService = Provider.of<PhraseService>(context, listen: false);
      if (!phraseService.isInitialized && !phraseService.isLoading) {
        phraseService.init();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openRandomPhrase(List<GermanPhrase> phrases) {
    if (phrases.isEmpty) return;
    final random = Random();
    final phrase = phrases[random.nextInt(phrases.length)];
    PhraseDetailSheet.show(context, phrase);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final bg = isDark ? const Color(0xFF181614) : const Color(0xFFFAF6F0);
    final rustAccent = const Color(0xFF8C2D19);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ALLTAGSSPRACHE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: rustAccent,
              ),
            ),
            Text(
              'Phrasen & Redemittel',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: inkColor,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showFavoritesOnly
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              color: _showFavoritesOnly ? Colors.amber[700] : inkColor,
            ),
            tooltip: _showFavoritesOnly ? 'Show All' : 'Show Bookmarked',
            onPressed: () {
              setState(() {
                _showFavoritesOnly = !_showFavoritesOnly;
              });
            },
          ),
          Consumer<PhraseService>(
            builder: (context, phraseService, _) {
              return IconButton(
                icon: const Icon(Icons.casino_outlined),
                tooltip: 'Random Phrase',
                onPressed: () =>
                    _openRandomPhrase(phraseService.allPhrases),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: rustAccent,
        foregroundColor: Colors.white,
        tooltip: 'Practice Quiz',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PhrasePracticeScreen(
                initialCategory:
                    _selectedCategory != 'All' ? _selectedCategory : null,
                initialLevel:
                    _selectedLevel != 'All' ? _selectedLevel : null,
              ),
            ),
          );
        },
        child: const Icon(Icons.fitness_center_rounded, size: 24),
      ),
      body: CappedWidth(
        child: Consumer<PhraseService>(
          builder: (context, phraseService, _) {
            if (phraseService.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final categories = ['All', ...phraseService.getCategories()];
            final levels = phraseService.getLevels();

            final filteredPhrases = phraseService.filterPhrases(
              category: _selectedCategory,
              level: _selectedLevel,
              query: _searchController.text,
              bookmarkedOnly: _showFavoritesOnly,
            );

            return Column(
              children: [
                // Top Search & Filter Bar
                Container(
                  color: Theme.of(context).cardColor,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    children: [
                      // Search TextField
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search German phrases or English meanings...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: inkColor.withValues(alpha: 0.5),
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: rustAccent,
                            size: 20,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: inkColor.withValues(alpha: 0.05),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(
                              color: inkColor.withValues(alpha: 0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(
                              color: inkColor.withValues(alpha: 0.2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: rustAccent, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Category Horizontal Carousel
                      SizedBox(
                        height: 32,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final cat = categories[index];
                            final isSelected = cat == _selectedCategory;

                            return ChoiceChip(
                              label: Text(cat),
                              selected: isSelected,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.white
                                    : inkColor.withValues(alpha: 0.8),
                              ),
                              selectedColor: rustAccent,
                              backgroundColor: inkColor.withValues(alpha: 0.06),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(3),
                                side: BorderSide(
                                  color: isSelected
                                      ? rustAccent
                                      : inkColor.withValues(alpha: 0.15),
                                ),
                              ),
                              showCheckmark: false,
                              onSelected: (_) {
                                setState(() {
                                  _selectedCategory = cat;
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Level Filter Pills + Count
                      Row(
                        children: [
                          Text(
                            'LEVEL: ',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: inkColor.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              children: levels.map((lvl) {
                                final isSelected = lvl == _selectedLevel;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedLevel = lvl;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? rustAccent.withValues(alpha: 0.15)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(
                                        color: isSelected
                                            ? rustAccent
                                            : inkColor.withValues(alpha: 0.2),
                                        width: isSelected ? 1.2 : 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      lvl,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected ? rustAccent : inkColor,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          Text(
                            '${filteredPhrases.length} phrases',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: inkColor.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Phrase List
                Expanded(
                  child: filteredPhrases.isEmpty
                      ? _buildEmptyState(context, inkColor)
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 88),
                          itemCount: filteredPhrases.length,
                          itemBuilder: (context, index) {
                            final phrase = filteredPhrases[index];
                            return PhraseCard(phrase: phrase);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color inkColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: inkColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No phrases found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: inkColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting your search terms or filters.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: inkColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
