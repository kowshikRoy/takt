import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/book_guide.dart';
import '../../models/textbook_unit.dart';
import '../../services/book_guide_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/gestures.dart';
import '../../widgets/glance_word_sheet.dart';
import '../../widgets/interactive_german_text.dart';
import '../../theme/books_modernist_style.dart';
import '../../widgets/books/sections/grammar_callout_card.dart';
import '../../widgets/books/sections/fill_in_statements_widget.dart';
import '../../widgets/books/sections/grammar_classification_widget.dart';
import '../../widgets/books/sections/image_ordering_widget.dart';
import '../../widgets/books/sections/phonetics_listening_widget.dart';
import '../../widgets/books/sections/phonetics_categorization_widget.dart';
import '../../widgets/books/sections/writing_exercise_widget.dart';
import '../../widgets/books/sections/reading_profiles_widget.dart';
import '../../widgets/books/sections/reading_matching_widget.dart';
import '../../widgets/capped_width.dart';

class TextbookUnitScreen extends StatefulWidget {
  final ChapterSummary chapterSummary;
  final String bookTitle;

  const TextbookUnitScreen({
    super.key,
    required this.chapterSummary,
    required this.bookTitle,
  });

  @override
  State<TextbookUnitScreen> createState() => _TextbookUnitScreenState();
}

class _TextbookUnitScreenState extends State<TextbookUnitScreen> {
  late PageController _pageController;
  TextbookUnit? _unit;
  bool _isLoading = true;
  int _selectedPageIndex = 0;
  final bool _isPracticeMode = true;
  final Map<String, String> _userAnswers = {};
  final Map<String, bool> _revealedAnswers = {};
  Set<String> _completedSectionIds = {};

  // Generic tap-to-match exercise state, keyed by section id.
  final Map<String, String?> _matchArmedLeft = {};
  final Map<String, Map<String, String>> _matchPaired = {};
  final Map<String, (String leftId, String rightId)?> _matchFlash = {};

  Future<void> _toggleSectionDone(String sectionId) async {
    setState(() {
      if (_completedSectionIds.contains(sectionId)) {
        _completedSectionIds.remove(sectionId);
      } else {
        _completedSectionIds.add(sectionId);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'completed_sections_unit_${_unit?.unitNumber ?? widget.chapterSummary.chapterNumber}',
      _completedSectionIds.toList(),
    );
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedPageIndex);
    _loadUnitData();
  }

  Future<void> _loadUnitData() async {
    final service = Provider.of<BookGuideService>(context, listen: false);
    String path = widget.chapterSummary.jsonAssetPath;
    if (widget.chapterSummary.chapterNumber == 1) {
      path = 'assets/books/netzwerk-a2/unit_01.json';
    } else if (widget.chapterSummary.chapterNumber == 2) {
      path = 'assets/books/netzwerk-a2/unit_02.json';
    }
    final data = await service.loadTextbookUnit(path);
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getStringList(
            'completed_sections_unit_${data?.unitNumber ?? widget.chapterSummary.chapterNumber}') ??
        [];
    final lastPageIndex = prefs.getInt('books_last_read_page_index') ?? 0;

    if (mounted) {
      setState(() {
        _unit = data;
        _completedSectionIds = completed.toSet();
        if (data != null && lastPageIndex >= 0 && lastPageIndex < data.pages.length) {
          _selectedPageIndex = lastPageIndex;
        } else {
          _selectedPageIndex = 0;
        }
        _pageController = PageController(initialPage: _selectedPageIndex);
        _isLoading = false;
      });
      _persistLastRead();
    }
  }

  Future<void> _persistLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('books_last_read_book_title', widget.bookTitle);
    await prefs.setInt(
        'books_last_read_chapter_number', widget.chapterSummary.chapterNumber);
    await prefs.setInt('books_last_read_page_index', _selectedPageIndex);
  }

  void _onPageSelected(int index) {
    setState(() {
      _selectedPageIndex = index;
    });
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
    _persistLastRead();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int get _totalSectionCount =>
      _unit?.pages.expand((p) => p.sections).length ?? 0;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: BooksModernist.readingTheme(context),
      child: Scaffold(
      backgroundColor: BooksModernist.bg,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: BooksModernist.accent))
            : _unit == null
                ? Center(
                    child: Text('Could not load unit data.',
                        style: BooksModernist.body()))
                : Column(
                    children: [
                      _buildHeader(),
                      Expanded(child: _buildPageView()),
                    ],
                  ),
      ),
      ),
    );
  }

  Widget _buildHeader() {
    final done = _completedSectionIds
        .where((id) => _unit!.pages
            .expand((p) => p.sections)
            .any((s) => s.id == id))
        .length;
    final total = _totalSectionCount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            children: [
              InkWell(
                onTap: () => Navigator.of(context).pop(),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(Icons.chevron_left_rounded, color: BooksModernist.text, size: 28),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kapitel ${_unit!.unitNumber}: ${_unit!.title}',
                      style: BooksModernist.heading(size: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$done / $total Abschnitte erledigt',
                      style: BooksModernist.body(
                        size: 11,
                        color: BooksModernist.text.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildHeaderActionButton(
                icon: Icons.menu_book_rounded,
                label: 'Grammatik',
                onTap: () => _showSupplementSheet(context, initialTab: 0),
              ),
              const SizedBox(width: 6),
              _buildHeaderActionButton(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Redemittel',
                onTap: () => _showSupplementSheet(context, initialTab: 1),
              ),
            ],
          ),
        ),
        _buildTopPageSlider(),
        ModernistProgressBar(
          progress: total > 0 ? done / total : 0,
          height: 3,
        ),
      ],
    );
  }

  Widget _buildTopPageSlider() {
    final pages = _unit?.pages ?? [];
    if (pages.length <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Page number displayed a few pixels directly above the active tapped bar
          Row(
            children: List.generate(pages.length, (index) {
              final isSelected = index == _selectedPageIndex;
              final pageNum = pages[index].pageNumber;

              return Expanded(
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: isSelected ? 1.0 : 0.0,
                    child: Text(
                      'S. $pageNum',
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

          // Segmented horizontal bars
          Row(
            children: List.generate(pages.length, (index) {
              final isSelected = index == _selectedPageIndex;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onPageSelected(index),
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index < pages.length - 1 ? 6.0 : 0.0,
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

  Widget _buildPagePillsBar() {
    final pages = _unit!.pages;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: pages.length,
        itemBuilder: (context, index) {
          final page = pages[index];
          final isSelected = index == _selectedPageIndex;

          return GestureDetector(
            onTap: () => _onPageSelected(index),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? BooksModernist.accent : BooksModernist.surface,
                border: Border.all(
                  color: isSelected ? BooksModernist.accent : BooksModernist.divider,
                ),
              ),
              child: Text(
                'Seite ${page.pageNumber}',
                style: BooksModernist.body(
                  size: 12,
                  weight: FontWeight.w700,
                  color: isSelected ? BooksModernist.bg : BooksModernist.text,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPageView() {
    final pages = _unit!.pages;

    return PageView.builder(
      controller: _pageController,
      itemCount: pages.length,
      onPageChanged: (index) {
        setState(() {
          _selectedPageIndex = index;
        });
        _persistLastRead();
      },
      itemBuilder: (context, index) {
        final page = pages[index];
        return _buildPageCard(context, page, index, pages.length);
      },
    );
  }

  Widget _buildPageCard(
      BuildContext context, PageModel page, int pageIndex, int totalPages) {
    return CappedWidth(
      maxWidth: 760,
      child: Column(
      children: [
        // 1. Bordered page content card (sharp corners, no curvature)
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            decoration: BoxDecoration(
              color: BooksModernist.surface,
              border: Border.all(color: BooksModernist.divider, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: page.sections
                    .map((section) => _buildSectionWidget(context, section))
                    .toList(),
              ),
            ),
          ),
        ),

        // 2. Page navigation bar OUTSIDE of the border
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: BooksModernist.bg,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (pageIndex > 0)
                InkWell(
                  onTap: () => _onPageSelected(pageIndex - 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                    child: Row(
                      children: [
                        Icon(Icons.chevron_left_rounded,
                            size: 18, color: BooksModernist.accentDark),
                        Text(
                          'Seite ${_unit!.pages[pageIndex - 1].pageNumber}',
                          style: BooksModernist.body(
                            size: 11,
                            weight: FontWeight.w700,
                            color: BooksModernist.accentDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),

              Text(
                '— Seite ${page.pageNumber} —',
                style: BooksModernist.body(
                  size: 11,
                  weight: FontWeight.w600,
                  color: BooksModernist.text.withValues(alpha: 0.4),
                ),
              ),

              if (pageIndex < totalPages - 1)
                InkWell(
                  onTap: () => _onPageSelected(pageIndex + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                    child: Row(
                      children: [
                        Text(
                          'Seite ${_unit!.pages[pageIndex + 1].pageNumber}',
                          style: BooksModernist.body(
                            size: 11,
                            weight: FontWeight.w700,
                            color: BooksModernist.accentDark,
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 18, color: BooksModernist.accentDark),
                      ],
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ],
      ),
    );
  }

  void _showSupplementSheet(BuildContext context, {int initialTab = 0}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SupplementSheet(
          unit: _unit!,
          initialTab: initialTab,
          buildGrammarTab: _buildGrammarTab,
          buildRedemittelTab: _buildRedemittelTab,
        );
      },
    );
  }

  Widget _buildSectionWidget(BuildContext context, SectionModel section) {
    final json = section.rawJson;
    final isDone = _completedSectionIds.contains(section.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with section ID and title/type
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!section.id.contains('_')) ...[
                ModernistTag(section.id.toUpperCase(), accent: true),
                const SizedBox(width: 10),
              ],
              if (section.title != null)
                Expanded(
                  child: InteractiveGermanText(
                    section.title!,
                    sourceTitle: _unit?.title,
                    style: BooksModernist.heading(size: 13.5),
                  ),
                )
              else
                Expanded(
                  child: Text(
                    section.type.replaceAll('_', ' ').toUpperCase(),
                    style: BooksModernist.body(
                      size: 11.5,
                      weight: FontWeight.w700,
                      color: BooksModernist.text.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              if (section.audioId != null || json['audio_id'] != null) ...[
                Icon(Icons.headphones_rounded, size: 14, color: BooksModernist.accentDark),
                const SizedBox(width: 3),
                Text(
                  'Hörtext ${section.audioId ?? json['audio_id']}',
                  style: BooksModernist.body(
                    size: 11,
                    weight: FontWeight.w700,
                    color: BooksModernist.accentDark,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Tooltip(
                message: isDone ? 'Als erledigt markiert' : 'Als erledigt markieren',
                child: InkWell(
                  onTap: () => _toggleSectionDone(section.id),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      isDone
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 22,
                      color: isDone
                          ? BooksModernist.accent
                          : BooksModernist.text.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Instruction
          if (section.instruction != null) ...[
            InteractiveGermanText(
              section.instruction!,
              sourceTitle: _unit?.title,
              style: BooksModernist.body(size: 13, weight: FontWeight.w600)
                  .copyWith(color: BooksModernist.text),
            ),
            const SizedBox(height: 12),
          ],

          // Reading matching (3a)
          if (json['headings'] is List && json['texts'] is List)
            ReadingMatchingWidget(
              sectionId: section.id,
              headings: json['headings'] as List,
              texts: json['texts'] as List,
              unitTitle: _unit?.title,
            )
          else ...[
            if (json['headings'] is List)
              _buildHeadingsList(context, json['headings'] as List),
            if (json['texts'] is List)
              _buildPersonTexts(context, json['texts'] as List),
          ],

          // Chat-reply matching (design's m6b) when both message lists are present.
          if (json['incoming_messages'] is List && json['ben_replies'] is List)
            _buildReplyMatching(context, section.id,
                json['incoming_messages'] as List, json['ben_replies'] as List),

          // Profiles / Reading Profiles
          if (section.profiles != null && section.profiles!.isNotEmpty)
            ReadingProfilesWidget(profiles: section.profiles, unitTitle: _unit?.title),

          // Chat Messages
          if (section.chatMessages != null && section.chatMessages!.isNotEmpty)
            _buildChatList(context, section.chatMessages!),
          if (json['chat_messages'] is List && section.chatMessages == null)
            _buildRawChatList(context, json['chat_messages'] as List),

          // Exercise Items
          if (section.items != null && section.items!.isNotEmpty)
            _buildExerciseList(context, section.items!),

          // Universal Grammar Callout Box
          if (json['grammar_callout'] is Map && section.type != 'grammar_classification')
            GrammarCalloutCard(
              callout: json['grammar_callout'] as Map<String, dynamic>,
              unitTitle: _unit?.title,
            ),

          // Speech Prompts
          if (json['speech_prompts'] is List)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (json['speech_prompts'] as List)
                    .map((p) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: BooksModernist.bg,
                            border: Border(left: BorderSide(color: BooksModernist.accent, width: 2.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '💬 „',
                                style: BooksModernist.body(size: 12, weight: FontWeight.w600),
                              ),
                              InteractiveGermanText(
                                p.toString(),
                                sourceTitle: _unit?.title,
                                style: BooksModernist.body(size: 12, weight: FontWeight.w600),
                              ),
                              Text(
                                '"',
                                style: BooksModernist.body(size: 12, weight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),

          // Note Taking
          if (json['note_taking'] is Map)
            WritingExerciseWidget(
              sectionId: 'notes_${section.id}',
              placeholder: (json['note_taking'] as Map)['placeholder']?.toString() ?? 'Stichpunkte notieren...',
            ),

          // Statements (fill in the blank / comprehension)
          if (json['statements'] is List)
            FillInStatementsWidget(
              sectionId: section.id,
              statements: json['statements'] as List,
              optionsList: json['options'] as List?,
              unitTitle: _unit?.title,
            ),

          // Causal matching (design's m7a) with a verified answer key.
          if (json['left_clauses'] is List && json['right_clauses'] is List)
            _buildCausalMatching(context, section.id,
                json['left_clauses'] as List, json['right_clauses'] as List),

          // Questions and answers (e.g. FAQ)
          if (json['questions'] is List && json['answers'] is List)
            _buildQAMatching(
                context, json['questions'] as List, json['answers'] as List),

          // Stations (interactive game)
          if (json['stations'] is List)
            _buildStationsList(context, json['stations'] as List),

          // WG Characters
          if (json['characters'] is List)
            _buildWGCharacters(context, json['characters'] as List),

          // Cultural Reading text
          if (json['text'] != null && section.type == 'cultural_reading')
            Container(
              padding: const EdgeInsets.all(14),
              color: BooksModernist.surface,
              child: InteractiveGermanText(
                json['text'].toString(),
                sourceTitle: _unit?.title,
                style: BooksModernist.body(size: 14).copyWith(height: 1.5),
              ),
            ),

          // Phonetics listening (5a)
          if (json['words'] is List && section.type == 'phonetics_listening')
            PhoneticsListeningWidget(
              sectionId: section.id,
              wordsList: json['words'] as List,
            ),

          // Phonetics categorization (5b)
          if (json['words_to_sort'] is List && section.type == 'phonetics_categorization')
            PhoneticsCategorizationWidget(
              sectionId: section.id,
              wordsList: json['words_to_sort'] as List,
              ruleCallout: json['rule_callout'] as Map<String, dynamic>?,
            ),

          // Listening Image Ordering (4c)
          if (json['image_items'] is List && section.type == 'listening_ordering')
            ImageOrderingWidget(
              sectionId: section.id,
              imageItems: json['image_items'] as List,
              speechBubble: json['speech_bubble']?.toString(),
            ),

          // Grammar Classification / Tables (4a)
          if (json['tables'] is List && section.type == 'grammar_classification')
            GrammarClassificationWidget(
              tablesList: json['tables'] as List,
              callout: json['grammar_callout'] as Map<String, dynamic>?,
              unitTitle: _unit?.title,
            ),

          // Free Writing Exercise (4d / writing)
          if (section.type == 'writing')
            WritingExerciseWidget(
              sectionId: section.id,
              placeholder: json['placeholder']?.toString() ?? 'Schreiben Sie hier...',
            ),

          // Example Speech
          if (json['example_speech'] != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: BooksModernist.accent, width: 2)),
              ),
              child: Text(
                '„${json['example_speech']}"',
                style: BooksModernist.body(size: 13, weight: FontWeight.w600),
              ),
            ),

          const ModernistDivider(margin: EdgeInsets.only(top: 4)),
        ],
      ),
    );
  }

  // ── Generic tap-to-match exercise engine ─────────────────────────────
  //
  // Mirrors the design's buildMatch()/selectLeft()/selectRight(): tap a left
  // item to arm it, then tap a right item — if it's the correct pair (per
  // answerKey) both items lock in as "paired"; otherwise both flash briefly
  // and stay tappable. In Solutions mode, every pair is shown pre-solved.

  void _selectLeft(String exKey, String id) {
    if (!_isPracticeMode) return;
    setState(() {
      final paired = _matchPaired[exKey] ?? {};
      if (paired.containsKey(id)) return;
      _matchArmedLeft[exKey] = _matchArmedLeft[exKey] == id ? null : id;
      _matchFlash[exKey] = null;
    });
  }

  void _selectRight(String exKey, String id, Map<String, String> answerKey) {
    if (!_isPracticeMode) return;
    final armed = _matchArmedLeft[exKey];
    if (armed == null) return;
    if (answerKey[armed] == id) {
      setState(() {
        final paired = Map<String, String>.from(_matchPaired[exKey] ?? {});
        paired[armed] = id;
        _matchPaired[exKey] = paired;
        _matchArmedLeft[exKey] = null;
        _matchFlash[exKey] = null;
      });
    } else {
      setState(() => _matchFlash[exKey] = (armed, id));
      Future.delayed(const Duration(milliseconds: 650), () {
        if (mounted) setState(() => _matchFlash[exKey] = null);
      });
    }
  }

  Widget _buildMatchExercise(
    BuildContext context, {
    required String exKey,
    required List<(String id, String label, String sub)> leftItems,
    required List<(String id, String label, String sub)> rightItems,
    required Map<String, String> answerKey,
  }) {
    final paired = _isPracticeMode ? (_matchPaired[exKey] ?? {}) : answerKey;
    final armed = _isPracticeMode ? _matchArmedLeft[exKey] : null;
    final flash = _matchFlash[exKey];
    final doneCount = paired.length;
    final total = answerKey.length;

    Widget itemBox({
      required String id,
      required String label,
      required String sub,
      required bool isLeft,
    }) {
      final isPaired = isLeft
          ? paired.containsKey(id)
          : paired.containsValue(id);
      final isArmed = isLeft && armed == id;
      final isFlash = flash != null && (isLeft ? flash.$1 == id : flash.$2 == id);
      String connector = '';
      if (isPaired) {
        final pairId = isLeft ? paired[id] : paired.entries.firstWhere((e) => e.value == id).key;
        final other = (isLeft ? rightItems : leftItems).firstWhere((e) => e.$1 == pairId);
        connector = isLeft ? '— ${other.$2} →' : '← ${other.$2}';
      }

      Color bg = BooksModernist.surface;
      Color border = BooksModernist.divider;
      Color fg = BooksModernist.text;
      if (isPaired) {
        bg = BooksModernist.accent100;
        border = BooksModernist.accent;
        fg = BooksModernist.accentDark;
      } else if (isFlash) {
        bg = BooksModernist.accent200;
        border = BooksModernist.accent600;
      } else if (isArmed) {
        border = BooksModernist.accent;
      }

      return InkWell(
        onTap: isPaired
            ? null
            : () => isLeft
                ? _selectLeft(exKey, id)
                : _selectRight(exKey, id, answerKey),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border, width: isArmed ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label.isNotEmpty)
                Text(label,
                    style: BooksModernist.heading(size: 13, color: fg)),
              if (sub.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: label.isNotEmpty ? 4 : 0),
                  child: Text(sub,
                      style: BooksModernist.body(size: 12, color: fg, weight: label.isEmpty ? FontWeight.w600 : null)),
                ),
              if (connector.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(connector,
                      style: BooksModernist.body(size: 11, weight: FontWeight.w700, color: fg)),
                ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$doneCount / $total zugeordnet',
                  style: BooksModernist.body(
                      size: 11, color: BooksModernist.text.withValues(alpha: 0.6))),
              if (doneCount > 0 && _isPracticeMode)
                InkWell(
                  onTap: () => setState(() => _matchPaired[exKey] = {}),
                  child: Text('Zurücksetzen',
                      style: BooksModernist.body(
                          size: 11,
                          weight: FontWeight.w700,
                          color: BooksModernist.accent)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: leftItems
                      .map((it) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: itemBox(
                                id: it.$1, label: it.$2, sub: it.$3, isLeft: true),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: rightItems
                      .map((it) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: itemBox(
                                id: it.$1, label: it.$2, sub: it.$3, isLeft: false),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildHeadingTextMatching(
    BuildContext context,
    String sectionId,
    List<dynamic> headings,
    List<dynamic> texts,
  ) {
    // Verified against Books.dc.html's M3A_ANSWER (Julia -> C, Jonas -> B).
    const answerKey = {'Julia': 'C', 'Jonas': 'B'};
    final leftItems = texts.map((t) {
      final map = t as Map<String, dynamic>;
      final person = map['person']?.toString() ?? '';
      return (person, person, '');
    }).toList();
    final rightItems = headings.map((h) {
      final map = h as Map<String, dynamic>;
      final id = map['id']?.toString() ?? '';
      return (id, '', '$id · ${map['title'] ?? ''}');
    }).toList();

    // If the real answer set doesn't cover every left item (different
    // chapter/content than the verified case), fall back to the old plain
    // read-only layout rather than guessing pairings.
    final coversAll = leftItems.every((l) => answerKey.containsKey(l.$1));
    if (!coversAll) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeadingsList(context, headings),
          _buildPersonTexts(context, texts),
        ],
      );
    }

    final hasFullTexts = texts.any(
        (t) => (t as Map)['text'] != null && (t['text'] as String).isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMatchExercise(
          context,
          exKey: sectionId,
          leftItems: leftItems,
          rightItems: rightItems,
          answerKey: answerKey,
        ),
        if (hasFullTexts) ...[
          const SizedBox(height: 14),
          _buildPersonTexts(context, texts),
        ],
      ],
    );
  }

  Widget _buildReplyMatching(
    BuildContext context,
    String sectionId,
    List<dynamic> incoming,
    List<dynamic> replies,
  ) {
    // Verified against Books.dc.html's M6B_ANSWER (Felix->3, Marvin->1, Lea->2).
    const answerKey = {'A': '3', 'B': '1', 'C': '2'};
    final leftItems = incoming.map((m) {
      final map = m as Map<String, dynamic>;
      final id = map['id']?.toString() ?? '';
      return (id, map['sender']?.toString() ?? '', map['text']?.toString() ?? '');
    }).toList();
    final rightItems = replies.map((r) {
      final map = r as Map<String, dynamic>;
      return (map['id']?.toString() ?? '', '', map['text']?.toString() ?? '');
    }).toList();

    final coversAll = leftItems.every((l) => answerKey.containsKey(l.$1));
    if (!coversAll) return const SizedBox.shrink();

    return _buildMatchExercise(
      context,
      exKey: sectionId,
      leftItems: leftItems,
      rightItems: rightItems,
      answerKey: answerKey,
    );
  }

  Widget _buildCausalMatching(
      BuildContext context, String sectionId, List<dynamic> lefts, List<dynamic> rights) {
    // Verified against Books.dc.html's M7A_ANSWER.
    const answerKey = {'1': 'D', '2': 'E', '3': 'C', '4': 'B', '5': 'A'};
    final leftItems = lefts.map((l) {
      final map = l as Map<String, dynamic>;
      final id = map['id']?.toString() ?? '';
      return (id, '', '$id. ${map['text'] ?? ''}');
    }).toList();
    final rightItems = rights.map((r) {
      final map = r as Map<String, dynamic>;
      final id = map['id']?.toString() ?? '';
      return (id, '', '$id. ${map['text'] ?? ''}');
    }).toList();

    final coversAll = leftItems.every((l) => answerKey.containsKey(l.$1));
    if (!coversAll) {
      // No verified answer key for this content — plain read-only fallback.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Satzanfang:', style: BooksModernist.heading(size: 13)),
          const SizedBox(height: 6),
          ...lefts.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${(l as Map)['id']}. ${l['text']}',
                    style: BooksModernist.body()),
              )),
          const SizedBox(height: 12),
          Text('Nebensatz mit weil:', style: BooksModernist.heading(size: 13)),
          const SizedBox(height: 6),
          ...rights.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${(r as Map)['id']}. ${r['text']}',
                    style: BooksModernist.body()),
              )),
        ],
      );
    }

    return _buildMatchExercise(
      context,
      exKey: sectionId,
      leftItems: leftItems,
      rightItems: rightItems,
      answerKey: answerKey,
    );
  }

  Widget _buildQAMatching(
      BuildContext context, List<dynamic> questions, List<dynamic> answers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fragen:', style: BooksModernist.heading(size: 13)),
        const SizedBox(height: 6),
        ...questions.map((q) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${(q as Map)['id']}. ${q['question']}',
                style: BooksModernist.body(weight: FontWeight.w600),
              ),
            )),
        const SizedBox(height: 12),
        Text('Antworten:', style: BooksModernist.heading(size: 13)),
        const SizedBox(height: 6),
        ...answers.map((a) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              color: BooksModernist.surface,
              child: Text(
                '${(a as Map)['id']}: ${a['text']}',
                style: BooksModernist.body(size: 13),
              ),
            )),
      ],
    );
  }

  Widget _buildProfilesList(BuildContext context, List<ProfileModel> profiles) {
    return Column(
      children: profiles.map((p) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          color: BooksModernist.surface,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                color: BooksModernist.text,
                child: Text(
                  p.name.isNotEmpty ? p.name[0] : '?',
                  style: BooksModernist.heading(size: 13, color: BooksModernist.bg),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: BooksModernist.heading(size: 14)),
                    const SizedBox(height: 4),
                    InteractiveGermanText(
                      p.text,
                      sourceTitle: _unit?.title,
                      style: BooksModernist.body(size: 13).copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChatList(BuildContext context, List<ChatMessageModel> messages) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: BooksModernist.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bubbleMaxWidth = constraints.maxWidth * 0.75;
          return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: messages.map((m) {
          final isMe = m.sender == 'Ben';
          return Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isMe ? BooksModernist.text : BooksModernist.bg,
                border: isMe ? null : Border.all(color: BooksModernist.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        m.sender,
                        style: BooksModernist.body(
                          size: 11,
                          weight: FontWeight.w700,
                          color: (isMe ? BooksModernist.bg : BooksModernist.text)
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      if (m.time != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          m.time!,
                          style: BooksModernist.body(
                            size: 10,
                            color: (isMe ? BooksModernist.bg : BooksModernist.text)
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  InteractiveGermanText(
                    m.text,
                    sourceTitle: _unit?.title,
                    style: BooksModernist.body(
                      size: 13,
                      color: isMe ? BooksModernist.bg : BooksModernist.text,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildRawChatList(BuildContext context, List<dynamic> list) {
    final msgs = list.map((item) {
      final map = item as Map<String, dynamic>;
      return ChatMessageModel(
        id: map['id']?.toString() ?? '',
        sender: map['sender']?.toString() ?? '',
        text: map['text']?.toString() ?? '',
        time: map['time']?.toString(),
      );
    }).toList();
    return _buildChatList(context, msgs);
  }

  Widget _buildExerciseList(
      BuildContext context, List<ExerciseItemModel> items) {
    return Column(
      children: items.map((item) {
        final key = '${item.id}_${item.prompt}';
        final selectedAns = _userAnswers[key];
        final isCorrect = selectedAns != null &&
            item.answer != null &&
            selectedAns.trim().toLowerCase() ==
                item.answer!.trim().toLowerCase();
        final isWrong = selectedAns != null && !isCorrect;
        final isRevealed = _revealedAnswers[key] == true;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: BooksModernist.surface,
            border: selectedAns != null
                ? Border.all(
                    color: isCorrect ? BooksModernist.accent : BooksModernist.accent600,
                    width: 1.5,
                  )
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                color: selectedAns != null
                    ? (isCorrect ? BooksModernist.accent100 : BooksModernist.accent200)
                    : BooksModernist.bg,
                child: Text(
                  item.id,
                  style: BooksModernist.heading(
                    size: 12,
                    color: selectedAns != null
                        ? (isCorrect ? BooksModernist.accentDark : BooksModernist.accent600)
                        : BooksModernist.accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InteractiveGermanText(
                      item.prompt,
                      sourceTitle: _unit?.title,
                      style: BooksModernist.heading(size: 14),
                    ),
                    const SizedBox(height: 8),

                    if (_isPracticeMode &&
                        item.options != null &&
                        item.options!.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: item.options!.map((opt) {
                          final isThisSelected = selectedAns == opt;
                          Color bg = BooksModernist.bg;
                          Color fg = BooksModernist.text;
                          Color border = BooksModernist.divider;
                          if (isThisSelected) {
                            if (isCorrect) {
                              bg = BooksModernist.accent;
                              fg = BooksModernist.bg;
                              border = BooksModernist.accent;
                            } else {
                              bg = BooksModernist.accent600;
                              fg = Colors.white;
                              border = BooksModernist.accent600;
                            }
                          }
                          return InkWell(
                            onTap: () => setState(() => _userAnswers[key] = opt),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: bg, border: Border.all(color: border)),
                              child: Text(opt,
                                  style: BooksModernist.body(size: 13, weight: FontWeight.w600, color: fg)),
                            ),
                          );
                        }).toList(),
                      ),
                      if (isWrong)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Richtig ist: ${item.answer}',
                            style: BooksModernist.body(
                                size: 12, weight: FontWeight.w700, color: BooksModernist.accentDark),
                          ),
                        ),
                    ] else if (_isPracticeMode) ...[
                      if (!isRevealed)
                        InkWell(
                          onTap: () => setState(() => _revealedAnswers[key] = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(border: Border.all(color: BooksModernist.divider)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.visibility_outlined, size: 14, color: BooksModernist.accent),
                                const SizedBox(width: 6),
                                Text('Lösung anzeigen',
                                    style: BooksModernist.body(size: 12, weight: FontWeight.w700, color: BooksModernist.accent)),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        if (item.answer != null)
                          Text('→ ${item.answer}',
                              style: BooksModernist.body(size: 14, weight: FontWeight.w600, color: BooksModernist.accentDark)),
                        if (item.matchTarget != null)
                          Text(item.matchTarget!,
                              style: BooksModernist.body(size: 13, weight: FontWeight.w600, color: BooksModernist.accentDark)),
                      ],
                    ] else ...[
                      if (item.answer != null)
                        Text('→ ${item.answer}',
                            style: BooksModernist.body(size: 14, weight: FontWeight.w600, color: BooksModernist.accentDark)),
                      if (item.matchTarget != null)
                        Text(item.matchTarget!,
                            style: BooksModernist.body(size: 13, weight: FontWeight.w600, color: BooksModernist.accentDark)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopicsList(BuildContext context, List<dynamic> topics) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: topics.map((t) {
        final map = t as Map<String, dynamic>;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(border: Border.all(color: BooksModernist.divider)),
          child: Text('${map['id']}. ${map['label']}',
              style: BooksModernist.body(size: 12, weight: FontWeight.w600)),
        );
      }).toList(),
    );
  }

  Widget _buildHeadingsList(BuildContext context, List<dynamic> headings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: headings.map((h) {
        final map = h as Map<String, dynamic>;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Überschrift ${map['id']}: "${map['title']}"',
            style: BooksModernist.body(weight: FontWeight.w700, color: BooksModernist.accentDark),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPersonTexts(BuildContext context, List<dynamic> texts) {
    return Column(
      children: texts.map((item) {
        final map = item as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(14),
          color: BooksModernist.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(map['person']?.toString() ?? '',
                  style: BooksModernist.heading(size: 15, color: BooksModernist.accentDark)),
              const SizedBox(height: 6),
              InteractiveGermanText(
                map['text']?.toString() ?? '',
                sourceTitle: _unit?.title,
                style: BooksModernist.body(size: 13).copyWith(height: 1.4),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatementsList(
    BuildContext context,
    String sectionId,
    List<dynamic> statements,
    List<dynamic>? optionsList,
  ) {
    final stateKey = 'stmt_$sectionId';
    final userChoices = _userAnswers;
    final showSolutionKey = 'show_sol_$sectionId';
    final showSolution = userChoices[showSolutionKey] == 'true';

    final options = optionsList != null
        ? optionsList.map((e) => e.toString()).toList()
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Word Bank Header (if options provided)
        if (options.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BooksModernist.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: BooksModernist.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.style_outlined, size: 16, color: BooksModernist.accentDark),
                    const SizedBox(width: 6),
                    Text(
                      'Auswahl-Pool',
                      style: BooksModernist.heading(size: 12.5, color: BooksModernist.accentDark),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: options.map((opt) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: BooksModernist.bg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: BooksModernist.divider),
                      ),
                      child: Text(
                        opt,
                        style: BooksModernist.body(size: 11.5, weight: FontWeight.w700),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Statements List
        ...statements.map((st) {
          final map = st as Map<String, dynamic>;
          final id = map['id']?.toString() ?? '';
          final text = map['text']?.toString() ?? '';
          final correctAns = map['answer']?.toString() ?? '';
          final itemKey = '${stateKey}_$id';
          final selected = userChoices[itemKey];
          final hasSelection = selected != null && selected.isNotEmpty;
          final isCorrect = hasSelection && selected == correctAns;

          // Clean text removing leading '...' if present for inline blank
          final cleanText = text.startsWith('...') ? text.substring(3).trim() : text;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: BooksModernist.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: showSolution
                    ? BooksModernist.accent
                    : (hasSelection
                        ? (isCorrect ? BooksModernist.accent : BooksModernist.accent600)
                        : BooksModernist.divider),
                width: (hasSelection || showSolution) ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '$id.',
                      style: BooksModernist.heading(
                        size: 13,
                        color: BooksModernist.text.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Inline Fill-in Slot
                    if (options.isNotEmpty)
                      PopupMenuButton<String>(
                        onSelected: (val) {
                          setState(() => userChoices[itemKey] = val);
                        },
                        itemBuilder: (ctx) => options.map((opt) {
                          return PopupMenuItem<String>(
                            value: opt,
                            child: Text(
                              opt,
                              style: BooksModernist.body(
                                size: 12.5,
                                weight: opt == selected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          );
                        }).toList(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: hasSelection
                                ? BooksModernist.accent100
                                : BooksModernist.bg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: hasSelection ? BooksModernist.accent : BooksModernist.divider,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                hasSelection ? selected : '________',
                                style: BooksModernist.body(
                                  size: 12.5,
                                  weight: FontWeight.w700,
                                  color: hasSelection
                                      ? BooksModernist.accentDark
                                      : BooksModernist.text.withValues(alpha: 0.4),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 18,
                                color: BooksModernist.accent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (options.isNotEmpty) const SizedBox(width: 8),

                    Expanded(
                      child: InteractiveGermanText(
                        cleanText,
                        sourceTitle: _unit?.title,
                        style: BooksModernist.body(size: 13),
                      ),
                    ),
                  ],
                ),

                // Validation / Solution message (only when solution is toggled OR when checked)
                if (showSolution && correctAns.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '✓ Lösung: $correctAns',
                    style: BooksModernist.body(
                      size: 11,
                      weight: FontWeight.w700,
                      color: BooksModernist.accentDark,
                    ),
                  ),
                ] else if (hasSelection) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        size: 14,
                        color: isCorrect ? BooksModernist.accent : BooksModernist.accent600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isCorrect ? 'Richtig!' : 'Falsch. Versuchen Sie es noch einmal.',
                        style: BooksModernist.body(
                          size: 10.5,
                          weight: FontWeight.w600,
                          color: isCorrect ? BooksModernist.accent : BooksModernist.accent600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        }),

        // Action Buttons: Reset & Toggle Solution
        const SizedBox(height: 6),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  userChoices[showSolutionKey] = showSolution ? 'false' : 'true';
                });
              },
              icon: Icon(
                showSolution ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 16,
              ),
              label: Text(
                showSolution ? 'Lösung ausblenden' : 'Lösung anzeigen',
                style: BooksModernist.body(size: 11.5, weight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: BooksModernist.accentDark,
                side: BorderSide(color: BooksModernist.accent),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  for (final st in statements) {
                    final id = (st as Map)['id']?.toString() ?? '';
                    userChoices.remove('${stateKey}_$id');
                  }
                  userChoices.remove(showSolutionKey);
                });
              },
              child: Text(
                'Zurücksetzen',
                style: BooksModernist.body(
                  size: 11.5,
                  color: BooksModernist.text.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGrammarCalloutBox(BuildContext context, Map<String, dynamic> callout) {
    final title = callout['title']?.toString() ?? 'G Grammatik';
    final formula = callout['formula']?.toString();
    final examples = callout['examples'] is List ? (callout['examples'] as List) : [];
    final rules = callout['rules'] is List ? (callout['rules'] as List) : [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BooksModernist.accent100.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BooksModernist.accent, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BooksModernist.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'G',
                  style: BooksModernist.heading(size: 15, color: BooksModernist.bg),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: BooksModernist.heading(size: 14, color: BooksModernist.accentDark),
                    ),
                    if (formula != null)
                      Text(
                        formula,
                        style: BooksModernist.body(size: 12, weight: FontWeight.w700, color: BooksModernist.accentDark),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (examples.isNotEmpty || rules.isNotEmpty) const SizedBox(height: 10),
          ...examples.map((ex) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: InteractiveGermanText(
                  ex.toString(),
                  sourceTitle: _unit?.title,
                  style: BooksModernist.body(size: 12.5, weight: FontWeight.w600),
                ),
              )),
          ...rules.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '• ${r.toString()}',
                  style: BooksModernist.body(size: 11.5),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildStationsList(BuildContext context, List<dynamic> stations) {
    return Column(
      children: stations.map((st) {
        final map = st as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          color: BooksModernist.accent100,
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                color: BooksModernist.accent,
                child: Text(map['station']?.toString() ?? '',
                    style: BooksModernist.heading(size: 13, color: BooksModernist.bg)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(map['sense']?.toString() ?? '',
                        style: BooksModernist.heading(size: 13, color: BooksModernist.accentDark)),
                    Text(map['description']?.toString() ?? '', style: BooksModernist.body(size: 13)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWGCharacters(BuildContext context, List<dynamic> characters) {
    return Column(
      children: characters.map((c) {
        final map = c as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          color: BooksModernist.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(map['name']?.toString() ?? '',
                  style: BooksModernist.heading(size: 16, color: BooksModernist.accentDark)),
              const SizedBox(height: 6),
              Text('Beruf: ${map['job'] ?? ''}', style: BooksModernist.body(weight: FontWeight.w700)),
              Text('Typisch: ${map['typical'] ?? ''}', style: BooksModernist.body()),
              Text('Hobby: ${map['hobby'] ?? ''}', style: BooksModernist.body()),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPhoneticsListening(
      BuildContext context, String sectionId, List<dynamic> wordsList) {
    final stateKey = 'phonetics_$sectionId';
    final userChoices = _userAnswers;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - 72) / 2;
        return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: wordsList.map((item) {
            final map = item is Map ? item : <String, dynamic>{};
            final id = map['id']?.toString() ?? (item is String ? item : '');
            final word = map['word']?.toString() ?? (item is String ? item : '');
            final correctAns = map['answer']?.toString() ??
                map['sound']?.toString() ??
                (RegExp(r'(ach|och|uch|auch)', caseSensitive: false).hasMatch(word) ? 'acht' : 'ich');
            final itemKey = '${stateKey}_$id';
            final selected = userChoices[itemKey];
            final isDone = selected != null;
            final isCorrect = selected == correctAns;

            return Container(
              width: tileWidth,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: BooksModernist.surface,
                border: Border.all(
                  color: isDone
                      ? (isCorrect ? BooksModernist.accent : BooksModernist.accent600)
                      : BooksModernist.divider,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word,
                    style: BooksModernist.heading(size: 13.5),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _choiceButton(
                          label: 'wie ich',
                          active: selected == 'ich',
                          onTap: () => setState(() => userChoices[itemKey] = 'ich'),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _choiceButton(
                          label: 'wie acht',
                          active: selected == 'acht',
                          onTap: () => setState(() => userChoices[itemKey] = 'acht'),
                        ),
                      ),
                    ],
                  ),
                  if (!_isPracticeMode || isDone) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Richtig: wie $correctAns',
                      style: BooksModernist.body(
                        size: 10,
                        weight: FontWeight.w700,
                        color: BooksModernist.accentDark,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ],
        );
      },
    );
  }

  Widget _choiceButton({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? BooksModernist.accent : BooksModernist.bg,
          border: Border.all(
            color: active ? BooksModernist.accent : BooksModernist.divider,
          ),
        ),
        child: Text(
          label,
          style: BooksModernist.body(
            size: 10.5,
            weight: FontWeight.w700,
            color: active ? BooksModernist.bg : BooksModernist.text,
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneticsCategorization(
    BuildContext context,
    String sectionId,
    List<dynamic> wordsList,
    Map<String, dynamic>? ruleCallout,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ruleCallout != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BooksModernist.accent100,
              border: Border(left: BorderSide(color: BooksModernist.accent, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: BooksModernist.accentDark),
                    const SizedBox(width: 6),
                    Text(
                      ruleCallout['title']?.toString() ?? 'Ausspracheregel: ch',
                      style: BooksModernist.heading(size: 13, color: BooksModernist.accentDark),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (ruleCallout['wie_acht'] != null)
                  Text(ruleCallout['wie_acht'].toString(),
                      style: BooksModernist.body(size: 11.5)),
                if (ruleCallout['wie_ich'] != null)
                  Text(ruleCallout['wie_ich'].toString(),
                      style: BooksModernist.body(size: 11.5)),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildCategorizationColumn(
                title: 'wie ich',
                sectionId: sectionId,
                category: 'ich',
                wordsList: wordsList,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildCategorizationColumn(
                title: 'wie acht',
                sectionId: sectionId,
                category: 'acht',
                wordsList: wordsList,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategorizationColumn({
    required String title,
    required String sectionId,
    required String category,
    required List<dynamic> wordsList,
  }) {
    final catWords = wordsList.where((item) {
      String targetCat = '';
      if (item is Map) {
        targetCat = item['category']?.toString() ??
            item['sound']?.toString() ??
            item['answer']?.toString() ??
            '';
      } else if (item is String) {
        final lower = item.toLowerCase();
        if (RegExp(r'(ach|och|uch|auch)').hasMatch(lower)) {
          targetCat = 'acht';
        } else {
          targetCat = 'ich';
        }
      }
      return targetCat == category;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: BooksModernist.surface,
        border: Border.all(color: BooksModernist.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: BooksModernist.accent,
            child: Text(
              title,
              style: BooksModernist.body(
                size: 11.5,
                weight: FontWeight.w800,
                color: BooksModernist.bg,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...catWords.map((item) {
            final word = item is Map
                ? (item['word']?.toString() ?? '')
                : item.toString();
            return Container(
              margin: const EdgeInsets.only(bottom: 5),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              color: BooksModernist.bg,
              child: Text(
                word,
                style: BooksModernist.body(size: 12, weight: FontWeight.w600),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildImageOrdering(
    BuildContext context,
    String sectionId,
    List<dynamic> imageItems,
    String? speechBubble,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - 72) / 2;
        return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: imageItems.map((item) {
            final map = item as Map<String, dynamic>;
            final id = map['id']?.toString() ?? '';
            final label = map['label']?.toString() ?? '';
            final correct = map['correct_order'] as int? ?? 1;

            return Container(
              width: tileWidth,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: BooksModernist.surface,
                border: Border.all(color: BooksModernist.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 64,
                    color: BooksModernist.bg,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_outlined, size: 28, color: BooksModernist.accent),
                        const SizedBox(height: 2),
                        Text(
                          'Bild $id',
                          style: BooksModernist.heading(size: 11, color: BooksModernist.accentDark),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(label, style: BooksModernist.body(size: 11.5, weight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Reihenfolge:', style: BooksModernist.body(size: 10.5)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: BooksModernist.accent100,
                          border: Border.all(color: BooksModernist.accent),
                        ),
                        child: Text(
                          '# $correct',
                          style: BooksModernist.body(
                            size: 11,
                            weight: FontWeight.w800,
                            color: BooksModernist.accentDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        if (speechBubble != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: BooksModernist.bg,
              border: Border(left: BorderSide(color: BooksModernist.accent, width: 2.5)),
            ),
            child: Text(
              '💬 „$speechBubble"',
              style: BooksModernist.body(size: 12.5, weight: FontWeight.w600),
            ),
          ),
        ],
      ],
        );
      },
    );
  }

  Widget _buildGrammarClassification(
    BuildContext context,
    List<dynamic> tablesList,
    Map<String, dynamic>? callout,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (callout != null) _buildGrammarCalloutBox(context, callout),

        ...tablesList.map((t) {
          final tableMap = t as Map<String, dynamic>;
          final categoryTitle = tableMap['category']?.toString() ?? '';
          final columns = (tableMap['columns'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
          final rows = (tableMap['rows'] as List<dynamic>? ?? []);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            color: BooksModernist.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(categoryTitle,
                    style: BooksModernist.heading(size: 14, color: BooksModernist.accentDark)),
                const SizedBox(height: 8),
                Table(
                  border: TableBorder.all(color: BooksModernist.divider, width: 1),
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(color: BooksModernist.bg),
                      children: columns
                          .map((col) => Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(col,
                                    style: BooksModernist.body(
                                        size: 11, weight: FontWeight.w700)),
                              ))
                          .toList(),
                    ),
                    ...rows.map((r) {
                      final rowMap = r as Map<String, dynamic>;
                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(rowMap['ohne']?.toString() ?? '—',
                                style: BooksModernist.body(size: 11)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(rowMap['trennbar']?.toString() ?? '—',
                                style: BooksModernist.body(size: 11)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(rowMap['nicht_trennbar']?.toString() ?? '—',
                                style: BooksModernist.body(size: 11)),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildWritingExercise(
    BuildContext context,
    String sectionId,
    String placeholder,
  ) {
    final key = 'writing_$sectionId';
    final currentText = _userAnswers[key] ?? '';
    final wordCount = currentText.trim().isEmpty
        ? 0
        : currentText.trim().split(RegExp(r'\s+')).length;

    return Container(
      padding: const EdgeInsets.all(12),
      color: BooksModernist.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            maxLines: 5,
            controller: TextEditingController(text: currentText)
              ..selection = TextSelection.fromPosition(
                TextPosition(offset: currentText.length),
              ),
            onChanged: (val) {
              _userAnswers[key] = val;
              SharedPreferences.getInstance().then((prefs) {
                prefs.setString('writing_ans_$key', val);
              });
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: BooksModernist.body(
                  size: 12.5, color: BooksModernist.text.withValues(alpha: 0.4)),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: BooksModernist.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: BooksModernist.accent, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: BooksModernist.body(size: 13),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '💾 Automatisch gespeichert',
                style: BooksModernist.body(
                  size: 10.5,
                  color: BooksModernist.text.withValues(alpha: 0.5),
                ),
              ),
              Text(
                '$wordCount Wörter',
                style: BooksModernist.body(
                  size: 11,
                  weight: FontWeight.w700,
                  color: BooksModernist.accentDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrammarTab(BuildContext context) {
    final grammarList = _unit!.grammar;

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: grammarList.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final g = grammarList[index];
        return Container(
          padding: const EdgeInsets.all(16),
          color: BooksModernist.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(g.title, style: BooksModernist.heading(size: 16, color: BooksModernist.accentDark)),
              const SizedBox(height: 10),
              InteractiveGermanText(
                g.rule,
                sourceTitle: _unit?.title,
                style: BooksModernist.body(size: 13).copyWith(height: 1.4),
              ),
              const SizedBox(height: 12),
              ...g.examples.map((ex) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    color: BooksModernist.bg,
                    child: InteractiveGermanText(
                      ex,
                      sourceTitle: _unit?.title,
                      style: BooksModernist.mono(size: 12.5),
                    ),
                  )),
              if (g.tableData != null) ...[
                const SizedBox(height: 12),
                Table(
                  border: TableBorder(
                    top: BorderSide(color: BooksModernist.divider),
                    horizontalInside: BorderSide(color: BooksModernist.dividerThin),
                  ),
                  children: g.tableData!.entries.map((entry) {
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                          child: Text(entry.key,
                              style: BooksModernist.body(size: 13, weight: FontWeight.w700, color: BooksModernist.accentDark)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                          child: Text(entry.value.join(', '), style: BooksModernist.body(size: 13)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRedemittelTab(BuildContext context) {
    final redemittelList = _unit!.redemittel;

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: redemittelList.length,
      separatorBuilder: (_, _) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        final cat = redemittelList[index];
        return Container(
          padding: const EdgeInsets.all(16),
          color: BooksModernist.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cat.category, style: BooksModernist.heading(size: 16, color: BooksModernist.accentDark)),
              const SizedBox(height: 12),
              ...cat.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ModernistTag(item.title),
                        const SizedBox(height: 6),
                        ...item.phrases.map((phrase) => Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('· ',
                                      style: BooksModernist.body(weight: FontWeight.w800, color: BooksModernist.accent)),
                                  Expanded(
                                    child: InteractiveGermanText(
                                      phrase,
                                      sourceTitle: _unit?.title,
                                      style: BooksModernist.body(size: 13).copyWith(height: 1.3),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }
}



class _SupplementSheet extends StatefulWidget {
  final TextbookUnit unit;
  final int initialTab;
  final Widget Function(BuildContext) buildGrammarTab;
  final Widget Function(BuildContext) buildRedemittelTab;

  const _SupplementSheet({
    required this.unit,
    required this.initialTab,
    required this.buildGrammarTab,
    required this.buildRedemittelTab,
  });

  @override
  State<_SupplementSheet> createState() => _SupplementSheetState();
}

class _SupplementSheetState extends State<_SupplementSheet>
    with SingleTickerProviderStateMixin {
  late TabController _sheetTabController;

  @override
  void initState() {
    super.initState();
    _sheetTabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _sheetTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.82;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: BooksModernist.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: BooksModernist.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Kapitel ${widget.unit.unitNumber}: ${widget.unit.title}',
                        style: BooksModernist.heading(size: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      color: BooksModernist.text,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: BooksModernist.divider, width: 1.5),
              ),
            ),
            child: TabBar(
              controller: _sheetTabController,
              labelColor: BooksModernist.accent,
              unselectedLabelColor: BooksModernist.text,
              indicatorColor: BooksModernist.accent,
              indicatorWeight: 2,
              labelStyle: BooksModernist.body(size: 13, weight: FontWeight.w700),
              unselectedLabelStyle: BooksModernist.body(size: 13, weight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Grammatik'),
                Tab(text: 'Redemittel'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _sheetTabController,
              children: [
                widget.buildGrammarTab(context),
                widget.buildRedemittelTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

