import 'package:flutter/material.dart';
import 'package:takt/l10n/app_localizations.dart';
import '../../models/grammar_lesson.dart';
import '../../services/grammar_service.dart';
import '../../theme/books_modernist_style.dart';
import '../../widgets/capped_width.dart';
import 'grammar_lesson_screen.dart';

class GrammarLessonsListScreen extends StatefulWidget {
  final String? initialLevel;
  final String? initialCategory;

  const GrammarLessonsListScreen({
    super.key,
    this.initialLevel,
    this.initialCategory,
  });

  @override
  State<GrammarLessonsListScreen> createState() =>
      _GrammarLessonsListScreenState();
}

class _GrammarLessonsListScreenState extends State<GrammarLessonsListScreen> {
  final GrammarService _grammarService = GrammarService();
  final TextEditingController _searchController = TextEditingController();

  List<GrammarLesson> _allLessons = [];
  bool _isLoading = true;
  String _selectedLevel = 'All';
  String _selectedCategory = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialLevel != null) {
      _selectedLevel = widget.initialLevel!;
    }
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    _loadLessons();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLessons() async {
    setState(() => _isLoading = true);
    final lessons = await _grammarService.getLessons();
    if (!mounted) return;
    setState(() {
      _allLessons = lessons;
      _isLoading = false;
    });
  }

  List<String> get _levels {
    final set = <String>{'All'};
    for (final l in _allLessons) {
      set.add(l.level);
    }
    return set.toList();
  }

  List<String> get _categories {
    final set = <String>{'All'};
    for (final l in _allLessons) {
      set.add(l.category);
    }
    return set.toList();
  }

  List<GrammarLesson> get _filteredLessons {
    return _allLessons.where((lesson) {
      final matchesLevel = _selectedLevel == 'All' ||
          lesson.level.contains(_selectedLevel) ||
          _selectedLevel.contains(lesson.level);

      final matchesCategory = _selectedCategory == 'All' ||
          lesson.category == _selectedCategory;

      final query = _searchQuery.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          lesson.title.toLowerCase().contains(query) ||
          lesson.subtitle.toLowerCase().contains(query) ||
          lesson.summary.toLowerCase().contains(query);

      return matchesLevel && matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF181614) : const Color(0xFFFAF6F0);
    final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFF2EEE7);
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    const rustAccent = Color(0xFF8C2D19);

    final completedCount = _allLessons
        .where((l) => _grammarService.isLessonCompleted(l.id))
        .length;
    final totalCount = _allLessons.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: inkColor, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n?.titleGrammarLessons ?? 'Grammatik-Bausteine',
          style: BooksModernist.heading(
            size: 18,
            color: inkColor,
            context: context,
          ).copyWith(fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: inkColor.withValues(alpha: 0.2),
            height: 1,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: rustAccent),
            )
          : CappedWidth(
              maxWidth: 720,
              child: RefreshIndicator(
                color: rustAccent,
                onRefresh: _loadLessons,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  children: [
                    // Overview / Progress Banner
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: inkColor.withValues(alpha: 0.2),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n?.sectionStructuredRoadmap ??
                                        'STRUCTURED GRAMMAR ROADMAP',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.1,
                                      color: rustAccent,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n?.labelLessonsCompleted(
                                          completedCount,
                                          totalCount,
                                        ) ??
                                        '$completedCount of $totalCount Lessons Completed',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: inkColor,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: rustAccent.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: rustAccent.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  '${(progress * 100).toInt()}%',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: rustAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: inkColor.withValues(alpha: 0.12),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                rustAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Search Bar
                    TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      style: TextStyle(fontSize: 14, color: inkColor),
                      decoration: InputDecoration(
                        hintText: l10n?.hintSearchGrammar ??
                            'Suche (z.B. Modalverben, weil, Perfekt)...',
                        hintStyle: TextStyle(
                          fontSize: 13.5,
                          color: inkColor.withValues(alpha: 0.5),
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: rustAccent,
                          size: 20,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: cardBg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(
                            color: inkColor.withValues(alpha: 0.2),
                            width: 1.2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(
                            color: rustAccent,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Level Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: _levels.map((lvl) {
                          final isSelected = _selectedLevel == lvl;
                          final label = lvl == 'All' ? (l10n?.labelAll ?? 'All') : lvl;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(label),
                              selected: isSelected,
                              onSelected: (val) {
                                if (val) {
                                  setState(() => _selectedLevel = lvl);
                                }
                              },
                              selectedColor: rustAccent,
                              backgroundColor: cardBg,
                              labelStyle: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : inkColor,
                              ),
                              side: BorderSide(
                                color: isSelected
                                    ? rustAccent
                                    : inkColor.withValues(alpha: 0.2),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Category Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: _categories.map((cat) {
                          final isSelected = _selectedCategory == cat;
                          final label = cat == 'All' ? (l10n?.labelAll ?? 'All') : cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(label),
                              selected: isSelected,
                              onSelected: (val) {
                                if (val) {
                                  setState(() => _selectedCategory = cat);
                                }
                              },
                              selectedColor: isDark
                                  ? const Color(0xFF382E28)
                                  : const Color(0xFFE2D6C5),
                              backgroundColor: cardBg,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: inkColor,
                              ),
                              side: BorderSide(
                                color: isSelected
                                    ? rustAccent
                                    : inkColor.withValues(alpha: 0.15),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Lesson List Cards
                    if (_filteredLessons.isEmpty) ...[
                      const SizedBox(height: 40),
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.menu_book_outlined,
                              size: 48,
                              color: inkColor.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n?.msgNoLessonsFound ?? 'Keine Lektionen gefunden',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: inkColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n?.msgTryDifferentFilter ??
                                  'Versuche einen anderen Filter oder Suchbegriff.',
                              style: TextStyle(
                                fontSize: 13,
                                color: inkColor.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ..._filteredLessons.map((lesson) {
                        final isCompleted =
                            _grammarService.isLessonCompleted(lesson.id);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isCompleted
                                  ? const Color(0xFF16A34A).withValues(alpha: 0.5)
                                  : inkColor.withValues(alpha: 0.2),
                              width: isCompleted ? 1.4 : 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.2 : 0.03,
                                ),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      GrammarLessonScreen(lesson: lesson),
                                ),
                              );
                              setState(() {}); // refresh completion state
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: rustAccent,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Text(
                                          lesson.level,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        lesson.category,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: inkColor.withValues(alpha: 0.6),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (isCompleted)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF16A34A)
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(3),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.check_circle_rounded,
                                                color: Color(0xFF16A34A),
                                                size: 13,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                l10n?.labelLessonDone ?? 'Done',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF16A34A),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    lesson.title,
                                    style: BooksModernist.heading(
                                      size: 16.5,
                                      color: inkColor,
                                      context: context,
                                    ).copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  if (lesson.subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      lesson.subtitle,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: rustAccent,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    lesson.summary,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.4,
                                      color: inkColor.withValues(alpha: 0.75),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.layers_outlined,
                                        size: 14,
                                        color: inkColor.withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        l10n?.labelGrammarBlocksCount(
                                              lesson.sections.length,
                                            ) ??
                                            '${lesson.sections.length} Bausteine (Structure, Tables, Rules)',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: inkColor.withValues(alpha: 0.6),
                                        ),
                                      ),
                                      const Spacer(),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 16,
                                        color: rustAccent,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
